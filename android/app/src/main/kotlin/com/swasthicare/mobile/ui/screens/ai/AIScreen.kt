package com.swasthicare.mobile.ui.screens.ai

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.data.models.ChatMessage
import com.swasthicare.mobile.data.models.HealthAnalysisResult
import com.swasthicare.mobile.data.models.QuickAction
import com.swasthicare.mobile.data.repository.AIConversation
import com.swasthicare.mobile.data.repository.AIMessageRecord
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIScreen(
    viewModel: AIViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Permission launcher for mic
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            viewModel.toggleRecording()
        }
    }

    // Image picker launchers
    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        viewModel.setSelectedImage(uri)
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        // For camera, we'd need a file URI; simplified here
        // In production, save bitmap to temp file and get URI
    }

    // Auto-scroll to bottom
    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    Scaffold(
        topBar = {},
        containerColor = MaterialTheme.colorScheme.background
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize()) {
            PremiumBackground()

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .imePadding()
            ) {
                // Header with history + bookmarks + clear buttons
                CenterAlignedTopAppBar(
                    title = { Text("Swastri AI", fontWeight = FontWeight.Bold) },
                    colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                        containerColor = Color.Transparent
                    ),
                    navigationIcon = {
                        IconButton(onClick = { viewModel.toggleHistorySheet() }) {
                            Box(
                                modifier = Modifier
                                    .glass(cornerRadius = 20.dp)
                                    .padding(8.dp)
                            ) {
                                Icon(Icons.Default.History, contentDescription = "History", modifier = Modifier.size(16.dp))
                            }
                        }
                    },
                    actions = {
                        IconButton(onClick = { viewModel.toggleBookmarksSheet() }) {
                            Box(
                                modifier = Modifier
                                    .glass(cornerRadius = 20.dp)
                                    .padding(8.dp)
                            ) {
                                Icon(Icons.Outlined.Bookmark, contentDescription = "Bookmarks", modifier = Modifier.size(16.dp))
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

                // Mode & Personality selectors
                ModePersonalityBar(
                    selectedMode = uiState.selectedMode,
                    selectedPersonality = uiState.selectedPersonality,
                    onModeChange = { viewModel.setMode(it) },
                    onPersonalityChange = { viewModel.setPersonality(it) }
                )

                // Chat content
                Box(modifier = Modifier.weight(1f)) {
                    if (uiState.messages.isEmpty() && uiState.showEmptyState) {
                        IntroView(
                            onAnalyzeClick = { viewModel.sendQuickAction(QuickAction.suggestions[0]) },
                            modifier = Modifier.align(Alignment.Center)
                        )
                    } else {
                        LazyColumn(
                            state = listState,
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                            modifier = Modifier.fillMaxSize()
                        ) {
                            items(uiState.messages, key = { it.id }) { message ->
                                ChatBubble(
                                    message = message,
                                    onBookmark = { viewModel.toggleBookmark(message.id) },
                                    onThumbsUp = { viewModel.sendFeedback(message.id, true) },
                                    onThumbsDown = { viewModel.sendFeedback(message.id, false) }
                                )
                            }
                        }
                    }
                }

                // Selected image preview
                if (uiState.selectedImageUri != null) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp)
                            .glass(cornerRadius = 12.dp)
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Image, contentDescription = null, modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Image attached", style = MaterialTheme.typography.bodySmall)
                        Spacer(modifier = Modifier.weight(1f))
                        IconButton(onClick = { viewModel.clearSelectedImage() }, modifier = Modifier.size(24.dp)) {
                            Icon(Icons.Default.Close, contentDescription = "Remove", modifier = Modifier.size(16.dp))
                        }
                    }
                }

                ChatInputBar(
                    inputText = uiState.inputText,
                    onTextChanged = viewModel::onInputTextChanged,
                    onSendClick = viewModel::sendMessage,
                    onQuickActionClick = viewModel::sendQuickAction,
                    onMicClick = {
                        if (uiState.isRecording) {
                            viewModel.toggleRecording()
                        } else {
                            permissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                        }
                    },
                    onImageClick = { galleryLauncher.launch("image/*") },
                    isRecording = uiState.isRecording,
                    showSuggestions = uiState.messages.isEmpty(),
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

            // Error Toast
            if (uiState.error != null) {
                Snackbar(
                    modifier = Modifier
                        .padding(16.dp)
                        .align(Alignment.TopCenter),
                    action = {
                        TextButton(onClick = { viewModel.clearError() }) {
                            Text("Dismiss", color = MaterialTheme.colorScheme.onErrorContainer)
                        }
                    },
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                ) {
                    Text(uiState.error!!)
                }
            }

            // Medical Disclaimer Dialog
            if (uiState.showMedicalDisclaimer) {
                AlertDialog(
                    onDismissRequest = { viewModel.dismissMedicalDisclaimer() },
                    title = { Text("Medical Mode Disclaimer") },
                    text = {
                        Text(
                            "Medical mode uses specialized AI for health-related queries. " +
                            "This is NOT a substitute for professional medical advice, diagnosis, or treatment. " +
                            "Always consult your healthcare provider for medical concerns.\n\n" +
                            "Do you understand and wish to continue?"
                        )
                    },
                    confirmButton = {
                        TextButton(onClick = { viewModel.acceptMedicalDisclaimer() }) {
                            Text("I Understand")
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { viewModel.dismissMedicalDisclaimer() }) {
                            Text("Cancel")
                        }
                    }
                )
            }

            // Emergency Alert Dialog
            if (uiState.showEmergencyAlert) {
                AlertDialog(
                    onDismissRequest = { viewModel.dismissEmergencyAlert() },
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color.Red, modifier = Modifier.size(24.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Emergency Detected", color = Color.Red, fontWeight = FontWeight.Bold)
                        }
                    },
                    text = { Text(uiState.emergencyMessage) },
                    confirmButton = {
                        Button(
                            onClick = { viewModel.dismissEmergencyAlert() },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                        ) {
                            Text("I Understand", color = Color.White)
                        }
                    },
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            }

            // History Bottom Sheet
            if (uiState.showHistorySheet) {
                HistoryBottomSheet(
                    conversations = uiState.conversations,
                    onSelect = { viewModel.loadConversation(it.id) },
                    onDelete = { viewModel.deleteConversation(it.id) },
                    onDismiss = { viewModel.toggleHistorySheet() }
                )
            }

            // Bookmarks Bottom Sheet
            if (uiState.showBookmarksSheet) {
                BookmarksBottomSheet(
                    bookmarks = uiState.bookmarkedMessages,
                    onDismiss = { viewModel.toggleBookmarksSheet() }
                )
            }
        }
    }
}

// ── Mode & Personality Bar ──

@Composable
fun ModePersonalityBar(
    selectedMode: AIMode,
    selectedPersonality: AIPersonality,
    onModeChange: (AIMode) -> Unit,
    onPersonalityChange: (AIPersonality) -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        // Mode toggle
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            AIMode.entries.forEach { mode ->
                FilterChip(
                    selected = selectedMode == mode,
                    onClick = { onModeChange(mode) },
                    label = { Text(mode.label, style = MaterialTheme.typography.labelSmall) },
                    leadingIcon = if (mode == AIMode.Medical) {
                        { Icon(Icons.Default.LocalHospital, contentDescription = null, modifier = Modifier.size(14.dp)) }
                    } else null
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Personality dropdown
            var expanded by remember { mutableStateOf(false) }
            Box {
                FilterChip(
                    selected = true,
                    onClick = { expanded = true },
                    label = { Text(selectedPersonality.label, style = MaterialTheme.typography.labelSmall) },
                    trailingIcon = { Icon(Icons.Default.ArrowDropDown, contentDescription = null, modifier = Modifier.size(16.dp)) }
                )
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    AIPersonality.entries.forEach { personality ->
                        DropdownMenuItem(
                            text = { Text(personality.label) },
                            onClick = {
                                onPersonalityChange(personality)
                                expanded = false
                            }
                        )
                    }
                }
            }
        }
    }
}

// ── IntroView ──

@Composable
fun IntroView(
    onAnalyzeClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Rounded.AutoAwesome,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(40.dp)
            )
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = "Swastri AI",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Your personal health assistant.\nAsk me anything about your vitals, diet, or fitness.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                lineHeight = 24.sp
            )
        }

        Button(
            onClick = onAnalyzeClick,
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 12.dp)
        ) {
            Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Analyze Health")
        }
    }
}

// ── Chat Bubble with feedback & bookmark ──

@Composable
fun ChatBubble(
    message: ChatMessage,
    onBookmark: () -> Unit = {},
    onThumbsUp: () -> Unit = {},
    onThumbsDown: () -> Unit = {}
) {
    val isUser = message.isUser
    val align = if (isUser) Alignment.End else Alignment.Start
    val bgColor = if (isUser) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant
    val textColor = if (isUser) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
    val shape = if (isUser) RoundedCornerShape(20.dp, 4.dp, 20.dp, 20.dp) else RoundedCornerShape(4.dp, 20.dp, 20.dp, 20.dp)

    Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = align) {
        if (!isUser) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.primary)
                Text("Swastri", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                Text("just now", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
            }
            Spacer(modifier = Modifier.height(4.dp))
        }

        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .background(bgColor, shape)
                .padding(horizontal = 16.dp, vertical = 12.dp)
        ) {
            if (message.isLoading) {
                TypingIndicator()
            } else {
                Text(
                    text = parseMarkdown(message.content),
                    color = textColor,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        }

        // Feedback & bookmark actions for assistant messages
        if (!isUser && !message.isLoading) {
            Row(
                modifier = Modifier.padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                IconButton(onClick = onThumbsUp, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Default.ThumbUp, contentDescription = "Thumbs Up", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.outline)
                }
                IconButton(onClick = onThumbsDown, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Default.ThumbDown, contentDescription = "Thumbs Down", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.outline)
                }
                IconButton(onClick = onBookmark, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Default.BookmarkAdd, contentDescription = "Bookmark", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.outline)
                }
            }
        }
    }
}

// Basic markdown parser for bold
fun parseMarkdown(text: String): AnnotatedString {
    val builder = AnnotatedString.Builder()
    var currentIndex = 0
    val boldRegex = "\\*\\*(.*?)\\*\\*".toRegex()
    val matches = boldRegex.findAll(text)
    for (match in matches) {
        if (match.range.first > currentIndex) {
            builder.append(text.substring(currentIndex, match.range.first))
        }
        builder.withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
            append(match.groupValues[1])
        }
        currentIndex = match.range.last + 1
    }
    if (currentIndex < text.length) {
        builder.append(text.substring(currentIndex))
    }
    return builder.toAnnotatedString()
}

@Composable
fun TypingIndicator() {
    val transition = rememberInfiniteTransition()
    val alpha by transition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        repeat(3) {
            Box(modifier = Modifier.size(8.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha), CircleShape))
        }
    }
}

// ── Chat Input Bar with image button ──

@Composable
fun ChatInputBar(
    inputText: String,
    onTextChanged: (String) -> Unit,
    onSendClick: () -> Unit,
    onQuickActionClick: (QuickAction) -> Unit,
    onMicClick: () -> Unit,
    onImageClick: () -> Unit,
    isRecording: Boolean,
    showSuggestions: Boolean,
    isLoading: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 16.dp)
    ) {
        if (showSuggestions) {
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(bottom = 12.dp)
            ) {
                items(QuickAction.suggestions) { action ->
                    QuickActionButton(action = action, onClick = { onQuickActionClick(action) })
                }
            }
        }

        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .glass(cornerRadius = 28.dp)
                .padding(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Image picker button
            IconButton(
                onClick = onImageClick,
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f), CircleShape)
                    .size(36.dp)
            ) {
                Icon(
                    Icons.Default.Image,
                    contentDescription = "Attach Image",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp)
                )
            }

            Spacer(modifier = Modifier.width(4.dp))

            TextField(
                value = inputText,
                onValueChange = onTextChanged,
                placeholder = { Text("Ask Swastri...", fontSize = 14.sp) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent
                ),
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 4.dp),
                maxLines = 4,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSendClick() })
            )

            // Send Button
            IconButton(
                onClick = onSendClick,
                enabled = inputText.isNotEmpty() && !isLoading,
                modifier = Modifier
                    .background(
                        if (inputText.isNotEmpty()) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.3f),
                        CircleShape
                    )
                    .size(40.dp)
            ) {
                Icon(Icons.Default.ArrowUpward, contentDescription = "Send", tint = Color.White, modifier = Modifier.size(20.dp))
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Mic Button
            IconButton(
                onClick = onMicClick,
                modifier = Modifier
                    .background(
                        if (isRecording) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        CircleShape
                    )
                    .size(40.dp)
            ) {
                Icon(
                    if (isRecording) Icons.Default.Stop else Icons.Default.Mic,
                    contentDescription = "Mic",
                    tint = if (isRecording) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

@Composable
fun QuickActionButton(action: QuickAction, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        contentPadding = PaddingValues(0.dp),
        modifier = Modifier
            .glass(cornerRadius = 16.dp)
            .width(200.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(action.title, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurface)
            Text(
                action.prompt,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

// ── Analysis Result Overlay ──

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
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text("Health Analysis", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)

                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Assessment", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(state.result.analysis.assessment)
                            }
                        }

                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Insights", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(state.result.analysis.insights)
                            }
                        }

                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Recommendations", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                state.result.analysis.recommendations.forEachIndexed { index, rec ->
                                    Text("${index + 1}. $rec", modifier = Modifier.padding(vertical = 4.dp))
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
                        Icon(Icons.Default.Close, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(48.dp))
                        Text("Analysis failed: ${state.message}")
                        Button(onClick = onDismiss) { Text("Close") }
                    }
                }
                else -> {}
            }
        }
    }
}

// ── History Bottom Sheet ──

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryBottomSheet(
    conversations: List<AIConversation>,
    onSelect: (AIConversation) -> Unit,
    onDelete: (AIConversation) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .padding(bottom = 32.dp)
        ) {
            Text("Conversation History", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(16.dp))

            if (conversations.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(100.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("No conversations yet", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(conversations) { conversation ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                                .clickable { onSelect(conversation) }
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    conversation.title,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Text(
                                    conversation.created_at.take(10),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            IconButton(onClick = { onDelete(conversation) }, modifier = Modifier.size(32.dp)) {
                                Icon(Icons.Default.Delete, contentDescription = "Delete", modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
        }
    }
}

// ── Bookmarks Bottom Sheet ──

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookmarksBottomSheet(
    bookmarks: List<AIMessageRecord>,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .padding(bottom = 32.dp)
        ) {
            Text("Bookmarked Messages", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(16.dp))

            if (bookmarks.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(100.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("No bookmarks yet", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(bookmarks) { message ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Bookmark, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(message.role.replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    message.content,
                                    style = MaterialTheme.typography.bodyMedium,
                                    maxLines = 5,
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
