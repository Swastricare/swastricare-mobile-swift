package com.swasthicare.mobile.ui.screens.ai

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.rounded.AutoAwesome
import com.swasthicare.mobile.data.repository.AIConversation
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.data.models.ChatMessage
import com.swasthicare.mobile.data.models.HealthMetrics
import com.swasthicare.mobile.data.models.QuickAction
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.AppColors
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.style.TextOverflow
import com.swasthicare.mobile.ui.theme.PrimaryColor
import com.swasthicare.mobile.ui.theme.PremiumColor
import android.net.Uri
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import androidx.compose.foundation.Canvas
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIScreen(
    viewModel: AIViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val hapticFeedback = LocalHapticFeedback.current
    
    // Permission launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            viewModel.toggleRecording()
        }
    }
    
    // Auto-scroll to bottom
    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .imePadding()
        ) {
            // Header
            CenterAlignedTopAppBar(
                title = { Text("Swastri AI", fontWeight = FontWeight.Bold) },
                windowInsets = WindowInsets(0, 0, 0, 0),
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Transparent
                ),
                actions = {
                    IconButton(onClick = { viewModel.openHistorySheet() }) {
                        Box(
                            modifier = Modifier
                                .glass(cornerRadius = 20.dp)
                                .padding(8.dp)
                        ) {
                            Icon(Icons.Default.History, contentDescription = "Chat History", modifier = Modifier.size(16.dp))
                        }
                    }
                    IconButton(onClick = { viewModel.clearChat() }) {
                        Box(
                            modifier = Modifier
                                .glass(cornerRadius = 20.dp)
                                .padding(8.dp)
                        ) {
                            Icon(Icons.Default.Close, contentDescription = "Clear Chat", modifier = Modifier.size(16.dp))
                        }
                    }
                }
            )

            Box(modifier = Modifier.weight(1f)) {
                if (uiState.messages.isEmpty() && uiState.showEmptyState) {
                    IntroView(
                        onQuickActionClick = { action ->
                            hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            viewModel.sendQuickAction(action)
                        },
                        modifier = Modifier.align(Alignment.Center)
                    )
                } else {
                    LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        itemsIndexed(uiState.messages, key = { _, msg -> msg.id }) { index, message ->
                            ChatBubble(
                                message = message,
                                onAnimationComplete = { viewModel.markMessageAnimated(message.id) },
                                onCopy = { viewModel.onMessageCopied() },
                                onBookmark = { viewModel.onMessageBookmarked() }
                            )
                            // Show health metric card below AI bubble if response discusses health metrics and analysis data exists
                            val hasHealthMetrics = remember(message.id, message.content) {
                                containsHealthMetrics(message.content)
                            }
                            val completedAnalysis = uiState.analysisState as? AnalysisState.Completed
                            if (!message.isUser && !message.isLoading && hasHealthMetrics && completedAnalysis != null) {
                                HealthInsightCard(metrics = completedAnalysis.result.metrics)
                            }
                            // Show follow-up chips below the last AI message only
                            val isLastMessage = index == uiState.messages.size - 1
                            if (isLastMessage && !message.isUser && !message.isLoading) {
                                FollowUpChips(
                                    suggestions = uiState.followUpSuggestions,
                                    onChipClick = { viewModel.sendFollowUp(it) }
                                )
                            }
                        }
                    }
                    // Scroll-to-bottom FAB
                    val showScrollFab by remember {
                        derivedStateOf {
                            listState.firstVisibleItemIndex < (uiState.messages.size - 2) &&
                                uiState.messages.size > 2
                        }
                    }
                    androidx.compose.animation.AnimatedVisibility(
                        visible = showScrollFab,
                        enter = fadeIn() + scaleIn(),
                        exit = fadeOut() + scaleOut(),
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(8.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .glass(cornerRadius = 24.dp)
                                .clip(CircleShape)
                                .clickable {
                                    scope.launch {
                                        listState.animateScrollToItem(uiState.messages.size - 1)
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.ArrowDownward,
                                contentDescription = "Scroll to bottom",
                                tint = PrimaryColor,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }

            ChatInputBar(
                inputText = uiState.inputText,
                onTextChanged = viewModel::onInputTextChanged,
                onSendClick = {
                    hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    viewModel.sendMessage()
                },
                onMicClick = {
                    hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                    if (uiState.isRecording) {
                         viewModel.toggleRecording()
                    } else {
                        permissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                    }
                },
                isRecording = uiState.isRecording,
                isLoading = uiState.isLoading
            )
        }

        // Analysis Overlay
        if (uiState.analysisState !is AnalysisState.Idle) {
            AnalysisResultOverlay(
                state = uiState.analysisState,
                onDismiss = { viewModel.dismissAnalysis() }
            )
        }

        // Chat History Sheet
        if (uiState.showHistorySheet) {
            ChatHistorySheet(
                conversations = uiState.historyConversations,
                isLoading = uiState.isHistoryLoading,
                onConversationClick = { viewModel.loadConversation(it) },
                onDeleteClick = { viewModel.deleteConversationFromHistory(it.id) },
                onDismiss = { viewModel.closeHistorySheet() }
            )
        }

        // Error Toast
        if (uiState.error != null) {
            Snackbar(
                modifier = Modifier.padding(16.dp).align(Alignment.TopCenter),
                action = {
                    TextButton(onClick = { viewModel.clearError() }) {
                        Text("Dismiss", color = AppColors.onErrorContainer)
                    }
                },
                containerColor = AppColors.errorContainer,
                contentColor = AppColors.onErrorContainer
            ) {
                Text(uiState.error!!)
            }
        }
    }
}

@Composable
fun IntroView(
    onQuickActionClick: (QuickAction) -> Unit,
    modifier: Modifier = Modifier
) {
    val hapticFeedback = LocalHapticFeedback.current
    val quickActionIcons = listOf(
        Icons.Rounded.AutoAwesome,
        Icons.Default.Mic,
        Icons.Default.ArrowUpward,
        Icons.Default.ContentCopy
    )

    // Pulse animation for glow ring
    val infiniteTransition = rememberInfiniteTransition(label = "avatarPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    // Staggered card visibility states
    val cardVisible = remember { List(4) { mutableStateOf(false) } }
    cardVisible.forEachIndexed { index, state ->
        LaunchedEffect(Unit) {
            delay(80L * index)
            state.value = true
        }
    }

    Column(
        modifier = modifier.padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(28.dp)
    ) {
        // Animated AI Avatar
        Box(
            contentAlignment = Alignment.Center
        ) {
            // Outer glow ring (120dp) with pulse
            Box(
                modifier = Modifier
                    .size(120.dp)
                    .scale(pulseScale)
                    .background(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                PrimaryColor.copy(alpha = glowAlpha),
                                PremiumColor.RoyalBlueEnd.copy(alpha = glowAlpha * 0.4f),
                                Color.Transparent
                            )
                        ),
                        shape = CircleShape
                    )
            )
            // Avatar circle (100dp) with gradient fill
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(PrimaryColor, PremiumColor.RoyalBlueEnd)
                        ),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.AutoAwesome,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(44.dp)
                )
            }
        }

        // Welcome text
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Swastri AI",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = "How can I help you today?",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.6f)
            )
        }

        // 2x2 Glass Quick Action Grid
        val actions = QuickAction.suggestions
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            for (row in 0..1) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    for (col in 0..1) {
                        val index = row * 2 + col
                        val action = actions[index]
                        val icon = quickActionIcons[index]
                        val visible = cardVisible[index].value

                        AnimatedVisibility(
                            visible = visible,
                            enter = slideInVertically(
                                initialOffsetY = { it / 2 },
                                animationSpec = tween(400, easing = FastOutSlowInEasing)
                            ) + fadeIn(animationSpec = tween(400)),
                            modifier = Modifier.weight(1f)
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .glass(cornerRadius = 16.dp)
                                    .clickable {
                                        hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                        onQuickActionClick(action)
                                    }
                                    .padding(14.dp)
                            ) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Icon(
                                        imageVector = icon,
                                        contentDescription = null,
                                        tint = PrimaryColor,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Text(
                                        text = action.title,
                                        style = MaterialTheme.typography.labelLarge,
                                        fontWeight = FontWeight.SemiBold,
                                        color = Color.White,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = action.prompt,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color.White.copy(alpha = 0.5f),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatBubble(
    message: ChatMessage,
    onAnimationComplete: () -> Unit = {},
    onCopy: () -> Unit = {},
    onBookmark: () -> Unit = {}
) {
    val isUser = message.isUser

    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(message.id) { visible = true }

    var showMenu by remember(message.id) { mutableStateOf(false) }
    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current

    AnimatedVisibility(
        visible = visible,
        enter = slideInVertically(
            initialOffsetY = { it / 2 },
            animationSpec = tween(300, easing = LinearOutSlowInEasing)
        ) + fadeIn(animationSpec = tween(300))
    ) {
        if (isUser) {
            // --- User bubble: glassmorphic with accent border ---
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 48.dp),
                horizontalAlignment = Alignment.End
            ) {
                Box(
                    modifier = Modifier
                        .widthIn(max = 300.dp)
                        .glass(cornerRadius = 16.dp, accentColor = PrimaryColor)
                        .combinedClickable(
                            onClick = {},
                            onLongClick = { if (!message.isLoading) showMenu = true }
                        )
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    if (!message.imageUri.isNullOrEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            AsyncImage(
                                model = Uri.parse(message.imageUri),
                                contentDescription = "Attached image",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .heightIn(max = 180.dp)
                                    .clip(RoundedCornerShape(12.dp))
                            )
                            // Extract image type label from content "[Image: X-Ray] Please analyze..."
                            val rawContent = message.content
                            val typeLabel = if (rawContent.contains("[Image: ") && rawContent.contains("]")) {
                                rawContent.removePrefix("[Image: ").substringBefore("]").trim()
                            } else ""
                            if (typeLabel.isNotBlank()) {
                                Box(
                                    modifier = Modifier
                                        .background(PrimaryColor.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text(
                                        typeLabel,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = PrimaryColor,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                        }
                    } else {
                        Text(
                            text = parseMarkdown(message.content),
                            color = Color.White.copy(alpha = 0.95f),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }

                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Copy") },
                            leadingIcon = { Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(18.dp)) },
                            onClick = {
                                clipboardManager.setText(AnnotatedString(message.content))
                                showMenu = false
                                onCopy()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Share") },
                            leadingIcon = { Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp)) },
                            onClick = {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, message.content)
                                }
                                context.startActivity(Intent.createChooser(intent, "Share message"))
                                showMenu = false
                            }
                        )
                    }
                }
            }
        } else {
            // --- AI bubble: borderless, text floats on the gradient ---
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(end = 48.dp),
                horizontalAlignment = Alignment.Start
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        Icons.Rounded.AutoAwesome,
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                        tint = PrimaryColor
                    )
                    Text("Swastri", style = MaterialTheme.typography.labelSmall, color = PrimaryColor)
                }
                Spacer(modifier = Modifier.height(4.dp))

                Box(
                    modifier = Modifier
                        .combinedClickable(
                            onClick = {},
                            onLongClick = { if (!message.isLoading) showMenu = true }
                        )
                ) {
                    if (message.isLoading) {
                        Box(
                            modifier = Modifier
                                .glass(cornerRadius = 14.dp)
                                .padding(horizontal = 16.dp, vertical = 10.dp)
                        ) {
                            TypingIndicator()
                        }
                    } else if (message.shouldAnimate) {
                        TypewriterText(
                            fullText = message.content,
                            color = Color.White.copy(alpha = 0.95f),
                            style = MaterialTheme.typography.bodyLarge,
                            onAnimationComplete = onAnimationComplete
                        )
                    } else {
                        Text(
                            text = parseMarkdown(message.content),
                            color = Color.White.copy(alpha = 0.95f),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }

                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Copy") },
                            leadingIcon = { Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(18.dp)) },
                            onClick = {
                                clipboardManager.setText(AnnotatedString(message.content))
                                showMenu = false
                                onCopy()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Share") },
                            leadingIcon = { Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp)) },
                            onClick = {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, message.content)
                                }
                                context.startActivity(Intent.createChooser(intent, "Share message"))
                                showMenu = false
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Bookmark") },
                            leadingIcon = { Icon(Icons.Default.BookmarkBorder, contentDescription = null, modifier = Modifier.size(18.dp)) },
                            onClick = {
                                showMenu = false
                                onBookmark()
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Typewriter Text Animation
@Composable
fun TypewriterText(
    fullText: String,
    color: Color,
    style: androidx.compose.ui.text.TextStyle,
    charDelayMillis: Long = 15L,
    onAnimationComplete: () -> Unit = {}
) {
    var visibleCount by remember(fullText) { mutableIntStateOf(0) }
    val totalChars = fullText.length
    val isAnimating = visibleCount < totalChars

    // Blinking cursor while animating
    val cursorTransition = rememberInfiniteTransition(label = "cursor")
    val cursorAlpha by cursorTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cursorAlpha"
    )

    LaunchedEffect(fullText) {
        visibleCount = 0
        var i = 0
        while (i < totalChars) {
            delay(charDelayMillis)
            // Reveal faster through whitespace/punctuation runs
            val charsToReveal = when {
                fullText[i] == ' ' || fullText[i] == '\n' -> 2
                totalChars > 500 -> 3 // Speed up long messages
                else -> 1
            }
            i = (i + charsToReveal).coerceAtMost(totalChars)
            visibleCount = i
        }
        onAnimationComplete()
    }

    val displayedText = fullText.substring(0, visibleCount)
    val annotated = buildAnnotatedString {
        append(displayedText)
        if (isAnimating) {
            withStyle(SpanStyle(color = color.copy(alpha = cursorAlpha))) {
                append("▎")
            }
        }
    }
    Text(
        text = annotated,
        color = color,
        style = style
    )
}

private val INLINE_MARKDOWN_REGEX = "\\*\\*(.*?)\\*\\*|`(.*?)`|\\*(.*?)\\*|_(.*?)_".toRegex()

// Basic markdown parser for bold/italic
private fun parseMarkdown(text: String): AnnotatedString {
    val builder = AnnotatedString.Builder()
    val lines = text.split("\n")

    lines.forEachIndexed { lineIndex, rawLine ->
        if (lineIndex > 0) builder.append("\n")

        val isH2 = rawLine.startsWith("## ")
        val isH1 = !isH2 && rawLine.startsWith("# ")
        val isBullet = rawLine.startsWith("- ") || rawLine.startsWith("* ")

        val line = when {
            isH2 -> rawLine.removePrefix("## ")
            isH1 -> rawLine.removePrefix("# ")
            isBullet -> "• ${rawLine.drop(2)}"
            else -> rawLine
        }

        if (isH1) builder.pushStyle(SpanStyle(fontWeight = FontWeight.Bold, fontSize = 20.sp))
        else if (isH2) builder.pushStyle(SpanStyle(fontWeight = FontWeight.Bold, fontSize = 17.sp))

        // Inline: bold (**), italic (* or _), code (`)
        val inlineRegex = INLINE_MARKDOWN_REGEX
        var cursor = 0
        for (match in inlineRegex.findAll(line)) {
            if (match.range.first > cursor) builder.append(line.substring(cursor, match.range.first))
            val full = match.value
            when {
                full.startsWith("**") -> builder.withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(match.groupValues[1]) }
                full.startsWith("`") -> builder.withStyle(
                    SpanStyle(
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                        background = androidx.compose.ui.graphics.Color(0x22888888)
                    )
                ) { append(match.groupValues[2]) }
                full.startsWith("*") -> builder.withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(match.groupValues[3]) }
                full.startsWith("_") -> builder.withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(match.groupValues[4]) }
            }
            cursor = match.range.last + 1
        }
        if (cursor < line.length) builder.append(line.substring(cursor))

        if (isH1 || isH2) builder.pop()
    }

    return builder.toAnnotatedString()
}


private fun containsHealthMetrics(text: String): Boolean {
    val lower = text.lowercase()
    val keywords = listOf("steps", "heart rate", "sleep", "calorie", "blood pressure", "exercise", "weight")
    return keywords.count { lower.contains(it) } >= 2
}

private const val DOT_CYCLE_MS = 900
private const val DOT_RISE_MS = 300
private const val DOT_STAGGER_MS = 150
private const val DOT_MIN_ALPHA = 0.3f

@Composable
private fun TypingDot(transition: InfiniteTransition, delayMillis: Int): Float {
    val alpha by transition.animateFloat(
        initialValue = DOT_MIN_ALPHA,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = keyframes {
                durationMillis = DOT_CYCLE_MS
                DOT_MIN_ALPHA at delayMillis using LinearEasing
                1f at (delayMillis + DOT_RISE_MS) using LinearEasing
                DOT_MIN_ALPHA at (delayMillis + DOT_RISE_MS * 2) using LinearEasing
            },
            repeatMode = RepeatMode.Restart
        ),
        label = "dot$delayMillis"
    )
    return alpha
}

@Composable
fun TypingIndicator() {
    val transition = rememberInfiniteTransition(label = "typing")
    val a1 = TypingDot(transition, 0)
    val a2 = TypingDot(transition, DOT_STAGGER_MS)
    val a3 = TypingDot(transition, DOT_STAGGER_MS * 2)
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(modifier = Modifier.size(8.dp).background(PrimaryColor.copy(alpha = a1), CircleShape))
        Box(modifier = Modifier.size(8.dp).background(PrimaryColor.copy(alpha = a2), CircleShape))
        Box(modifier = Modifier.size(8.dp).background(PrimaryColor.copy(alpha = a3), CircleShape))
    }
}

@Composable
fun ChatInputBar(
    inputText: String,
    onTextChanged: (String) -> Unit,
    onSendClick: () -> Unit,
    onMicClick: () -> Unit,
    isRecording: Boolean,
    isLoading: Boolean
) {
    val sendEnabled = inputText.isNotEmpty() && !isLoading

    // Mic pulse animation
    val micPulse = rememberInfiniteTransition(label = "micPulse")
    val micRingScale by micPulse.animateFloat(
        initialValue = 1f,
        targetValue = 1.3f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "micRing"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .glass(cornerRadius = 28.dp)
                .padding(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextField(
                value = inputText,
                onValueChange = onTextChanged,
                placeholder = { Text("Ask anything...", fontSize = 14.sp, color = Color.White.copy(alpha = 0.4f)) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent
                ),
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 8.dp),
                maxLines = 4,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSendClick() })
            )

            // Gradient Send Button
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(
                        brush = if (sendEnabled) Brush.linearGradient(
                            colors = listOf(PrimaryColor, Color(0xFF7C3AED))
                        ) else Brush.linearGradient(
                            colors = listOf(Color.Gray.copy(alpha = 0.3f), Color.Gray.copy(alpha = 0.3f))
                        ),
                        shape = CircleShape
                    )
                    .clip(CircleShape)
                    .clickable(enabled = sendEnabled) { onSendClick() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.ArrowUpward,
                    contentDescription = "Send",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Pulsing Mic Button
            Box(contentAlignment = Alignment.Center) {
                if (isRecording) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .scale(micRingScale)
                            .background(AppColors.error.copy(alpha = 0.2f), CircleShape)
                    )
                }
                IconButton(
                    onClick = onMicClick,
                    modifier = Modifier
                        .background(
                            if (isRecording) AppColors.error else Color.White.copy(alpha = 0.1f),
                            CircleShape
                        )
                        .size(40.dp)
                ) {
                    Icon(
                        if (isRecording) Icons.Default.Stop else Icons.Default.Mic,
                        contentDescription = "Mic",
                        tint = if (isRecording) Color.White else Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}


@Composable
fun FollowUpChips(suggestions: List<String>, onChipClick: (String) -> Unit) {
    AnimatedVisibility(
        visible = suggestions.isNotEmpty(),
        enter = fadeIn() + expandVertically(),
        exit = fadeOut() + shrinkVertically()
    ) {
        LazyRow(
            contentPadding = PaddingValues(horizontal = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 8.dp)
        ) {
            items(suggestions) { suggestion ->
                Box(
                    modifier = Modifier
                        .glass(cornerRadius = 20.dp)
                        .clickable { onChipClick(suggestion) }
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = suggestion,
                        style = MaterialTheme.typography.bodySmall,
                        color = PrimaryColor,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalysisResultOverlay(
    state: AnalysisState,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .padding(bottom = 32.dp)
                .heightIn(min = 300.dp)
        ) {
            when (state) {
                is AnalysisState.Analyzing -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        CircularProgressIndicator()
                        Text("Analyzing your health metrics...")
                    }
                }
                is AnalysisState.Completed -> {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.verticalScroll(rememberScrollState())
                    ) {
                        Text("Health Analysis", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)

                        // Health Metrics Summary
                        Card(colors = CardDefaults.cardColors(containerColor = AppColors.primaryContainer.copy(alpha = 0.3f))) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Your Metrics", style = MaterialTheme.typography.titleMedium, color = AppColors.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                val m = state.result.metrics
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    MetricChip("Steps", "${m.steps}")
                                    MetricChip("Heart Rate", "${m.heartRate} bpm")
                                }
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    MetricChip("Sleep", m.sleep)
                                    MetricChip("Calories", "${m.activeCalories} kcal")
                                }
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    MetricChip("Exercise", "${m.exerciseMinutes} min")
                                    MetricChip("BP", m.bloodPressure)
                                }
                                if (m.weight != "--") {
                                    Spacer(modifier = Modifier.height(8.dp))
                                    MetricChip("Weight", "${m.weight} kg")
                                }
                            }
                        }

                        Card(colors = CardDefaults.cardColors(containerColor = AppColors.surfaceVariant.copy(alpha = 0.5f))) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Assessment", style = MaterialTheme.typography.titleMedium, color = AppColors.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(state.result.analysis.assessment)
                            }
                        }

                        if (state.result.analysis.insights.isNotBlank()) {
                            Card(colors = CardDefaults.cardColors(containerColor = AppColors.surfaceVariant.copy(alpha = 0.5f))) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text("Insights", style = MaterialTheme.typography.titleMedium, color = AppColors.primary)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(state.result.analysis.insights)
                                }
                            }
                        }

                        if (state.result.analysis.recommendations.isNotEmpty()) {
                            Card(colors = CardDefaults.cardColors(containerColor = AppColors.surfaceVariant.copy(alpha = 0.5f))) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text("Recommendations", style = MaterialTheme.typography.titleMedium, color = AppColors.primary)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    state.result.analysis.recommendations.forEachIndexed { index, rec ->
                                        Text("${index + 1}. $rec", modifier = Modifier.padding(vertical = 4.dp))
                                    }
                                }
                            }
                        }
                    }
                }
                is AnalysisState.Error -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null, tint = AppColors.error, modifier = Modifier.size(48.dp))
                        Text(
                            text = state.message,
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                        Button(onClick = onDismiss) { Text("Close") }
                    }
                }
                else -> {}
            }
        }
    }
}

@Composable
private fun MetricChip(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = PrimaryColor)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.5f))
    }
}

@Composable
private fun HealthInsightCard(metrics: HealthMetrics) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
    ) {
        // Radial glow behind card
        Canvas(
            modifier = Modifier
                .matchParentSize()
                .padding(16.dp)
        ) {
            drawCircle(
                color = PrimaryColor.copy(alpha = 0.08f),
                radius = 200.dp.toPx(),
                center = center
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    Icons.Rounded.AutoAwesome,
                    contentDescription = null,
                    tint = PrimaryColor,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    "Health Snapshot",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = PrimaryColor
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                MetricChip("Steps", "${metrics.steps}")
                MetricChip("Heart Rate", "${metrics.heartRate} bpm")
                MetricChip("Calories", "${metrics.activeCalories} kcal")
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                MetricChip("Sleep", metrics.sleep)
                MetricChip("Exercise", "${metrics.exerciseMinutes} min")
                if (metrics.bloodPressure != "--/--") {
                    MetricChip("BP", metrics.bloodPressure)
                } else {
                    Box(modifier = Modifier.width(60.dp))
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatHistorySheet(
    conversations: List<AIConversation>,
    isLoading: Boolean,
    onConversationClick: (AIConversation) -> Unit,
    onDeleteClick: (AIConversation) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            Text(
                text = "Chat History",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            when {
                isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxWidth().height(120.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = AppColors.primary)
                    }
                }
                conversations.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxWidth().height(120.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(
                                Icons.Default.History,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.3f),
                                modifier = Modifier.size(40.dp)
                            )
                            Text(
                                "No previous chats",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color.White.copy(alpha = 0.5f)
                            )
                        }
                    }
                }
                else -> {
                    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(conversations, key = { it.id }) { conversation ->
                            ChatHistoryItem(
                                conversation = conversation,
                                onClick = { onConversationClick(conversation) },
                                onDelete = { onDeleteClick(conversation) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChatHistoryItem(
    conversation: AIConversation,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    val formattedDate = remember(conversation.updated_at) {
        try {
            val instant = java.time.Instant.parse(conversation.updated_at)
            val zdt = instant.atZone(java.time.ZoneId.systemDefault())
            java.time.format.DateTimeFormatter.ofPattern("MMM d, yyyy").format(zdt)
        } catch (_: Exception) { "" }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 12.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(3.dp)
                .height(36.dp)
                .background(PrimaryColor, RoundedCornerShape(2.dp))
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = conversation.title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (formattedDate.isNotEmpty()) {
                Text(
                    text = formattedDate,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.5f)
                )
            }
        }
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete",
                tint = Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}
