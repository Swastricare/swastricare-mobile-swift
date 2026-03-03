package com.swasthicare.mobile.ui.screens.ai

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.data.models.ChatMessage
import com.swasthicare.mobile.data.models.HealthAnalysisResult
import com.swasthicare.mobile.data.models.QuickAction
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Teal color for Image Analysis mode
private val ImageAnalysisTeal = Color(0xFF009688)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIScreen(
    viewModel: AIViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    val clipboardManager = LocalClipboardManager.current

    // Permission launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            viewModel.toggleRecording()
        }
    }

    // Image picker launcher
    val imagePickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            viewModel.onImagePicked(it.toString())
        }
    }

    // Auto-scroll to bottom
    LaunchedEffect(uiState.messages.size, uiState.followUpSuggestions) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    // Snackbar effect
    LaunchedEffect(uiState.snackbarMessage) {
        uiState.snackbarMessage?.let { message ->
            snackbarHostState.showSnackbar(
                message = message,
                duration = SnackbarDuration.Short
            )
            viewModel.clearSnackbar()
        }
    }

    // Mode Switch Confirmation Dialog
    if (uiState.showModeSwitchDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.cancelModeSwitch() },
            icon = {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error
                )
            },
            title = { Text("Switch Mode?") },
            text = {
                Text("Switching modes will clear the current conversation. Continue?")
            },
            confirmButton = {
                TextButton(onClick = { viewModel.confirmModeSwitch() }) {
                    Text("Continue", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.cancelModeSwitch() }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Image Type Selection Sheet
    if (uiState.showImageTypeSheet) {
        ImageTypeSelectionSheet(
            onTypeSelected = { viewModel.onImageTypeSelected(it) },
            onDismiss = { viewModel.dismissImageTypeSheet() }
        )
    }

    Scaffold(
        topBar = {
            // Invisible top bar to respect safe area, content handles headers
        },
        snackbarHost = {
            SnackbarHost(hostState = snackbarHostState) { data ->
                Snackbar(
                    snackbarData = data,
                    containerColor = MaterialTheme.colorScheme.inverseSurface,
                    contentColor = MaterialTheme.colorScheme.inverseOnSurface,
                    shape = RoundedCornerShape(12.dp)
                )
            }
        },
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
                // Header
                CenterAlignedTopAppBar(
                    title = { Text("Swastri AI", fontWeight = FontWeight.Bold) },
                    colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                        containerColor = Color.Transparent
                    ),
                    actions = {
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

                // Mode Chips Row
                ModeChipsRow(
                    currentMode = uiState.currentMode,
                    onModeSelected = { viewModel.requestModeSwitch(it) }
                )

                // Image picker prompt for Image Analysis mode
                if (uiState.currentMode == AIMode.ImageAnalysis && uiState.messages.isEmpty() && uiState.showEmptyState) {
                    ImageAnalysisPrompt(
                        onPickImage = { imagePickerLauncher.launch("image/*") },
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                    )
                } else {
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
                                itemsIndexed(uiState.messages, key = { _, msg -> msg.id }) { index, message ->
                                    ChatBubble(
                                        message = message,
                                        onCopy = {
                                            clipboardManager.setText(AnnotatedString(message.content))
                                            viewModel.onMessageCopied()
                                        },
                                        onBookmark = {
                                            viewModel.onMessageBookmarked()
                                        }
                                    )

                                    // Show follow-up suggestions after the last AI message
                                    if (index == uiState.messages.lastIndex &&
                                        !message.isUser &&
                                        !message.isLoading &&
                                        uiState.followUpSuggestions.isNotEmpty()
                                    ) {
                                        Spacer(modifier = Modifier.height(8.dp))
                                        FollowUpSuggestions(
                                            suggestions = uiState.followUpSuggestions,
                                            onSuggestionClick = { viewModel.sendFollowUp(it) }
                                        )
                                    }
                                }
                            }
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
                    onImageClick = if (uiState.currentMode == AIMode.ImageAnalysis) {
                        { imagePickerLauncher.launch("image/*") }
                    } else null,
                    isRecording = uiState.isRecording,
                    showSuggestions = uiState.messages.isEmpty() && uiState.currentMode != AIMode.ImageAnalysis,
                    isLoading = uiState.isLoading,
                    isImageAnalysisMode = uiState.currentMode == AIMode.ImageAnalysis
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
        }
    }
}

// MARK: - Mode Chips Row

@Composable
fun ModeChipsRow(
    currentMode: AIMode,
    onModeSelected: (AIMode) -> Unit
) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.padding(bottom = 8.dp)
    ) {
        items(AIMode.entries.toList()) { mode ->
            val isSelected = mode == currentMode
            val containerColor = when {
                isSelected && mode == AIMode.ImageAnalysis -> ImageAnalysisTeal
                isSelected && mode == AIMode.Medical -> MaterialTheme.colorScheme.error.copy(alpha = 0.9f)
                isSelected -> MaterialTheme.colorScheme.primary
                else -> Color.Transparent
            }
            val contentColor = when {
                isSelected -> Color.White
                mode == AIMode.ImageAnalysis -> ImageAnalysisTeal
                mode == AIMode.Medical -> MaterialTheme.colorScheme.error
                else -> MaterialTheme.colorScheme.onSurfaceVariant
            }
            val icon: ImageVector = when (mode) {
                AIMode.General -> Icons.Default.AutoAwesome
                AIMode.Medical -> Icons.Default.LocalHospital
                AIMode.ImageAnalysis -> Icons.Default.CameraAlt
            }

            FilterChip(
                selected = isSelected,
                onClick = { onModeSelected(mode) },
                label = { Text(mode.label, fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal) },
                leadingIcon = {
                    Icon(
                        icon,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = contentColor
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = containerColor,
                    selectedLabelColor = contentColor,
                    containerColor = Color.Transparent,
                    labelColor = contentColor
                ),
                border = if (isSelected) {
                    BorderStroke(0.dp, Color.Transparent)
                } else {
                    BorderStroke(1.dp, contentColor.copy(alpha = 0.4f))
                }
            )
        }
    }
}

// MARK: - Image Analysis Prompt

@Composable
fun ImageAnalysisPrompt(
    onPickImage: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(100.dp)
                .background(ImageAnalysisTeal.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.CameraAlt,
                contentDescription = null,
                tint = ImageAnalysisTeal,
                modifier = Modifier.size(48.dp)
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Image Analysis",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "Upload medical images like X-rays, MRI scans, skin photos, or lab reports for AI-powered analysis.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            lineHeight = 24.sp
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = onPickImage,
            colors = ButtonDefaults.buttonColors(
                containerColor = ImageAnalysisTeal
            ),
            contentPadding = PaddingValues(horizontal = 28.dp, vertical = 14.dp)
        ) {
            Icon(Icons.Default.Image, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Select Image")
        }
    }
}

// MARK: - Image Type Selection Sheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImageTypeSelectionSheet(
    onTypeSelected: (ImageType) -> Unit,
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
                text = "What type of image is this?",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            Text(
                text = "Select the image type for more accurate analysis",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 20.dp)
            )

            // 2-column grid
            val imageTypes = ImageType.entries.toList()
            val rows = imageTypes.chunked(2)

            rows.forEach { rowItems ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    rowItems.forEach { imageType ->
                        ImageTypeOption(
                            imageType = imageType,
                            onClick = { onTypeSelected(imageType) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                    // Fill remaining space if odd number
                    if (rowItems.size == 1) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
fun ImageTypeOption(
    imageType: ImageType,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val icon = when (imageType) {
        ImageType.XRay -> Icons.Default.Science
        ImageType.MRI -> Icons.Default.MedicalServices
        ImageType.CTScan -> Icons.Default.LocalHospital
        ImageType.SkinPhoto -> Icons.Default.Photo
        ImageType.LabReport -> Icons.Default.Description
        ImageType.Prescription -> Icons.Default.Description
        ImageType.Other -> Icons.Default.MoreHoriz
    }

    val tintColor = when (imageType) {
        ImageType.XRay -> Color(0xFF42A5F5)
        ImageType.MRI -> Color(0xFFAB47BC)
        ImageType.CTScan -> Color(0xFF26A69A)
        ImageType.SkinPhoto -> Color(0xFFEF5350)
        ImageType.LabReport -> Color(0xFFFFA726)
        ImageType.Prescription -> Color(0xFF66BB6A)
        ImageType.Other -> Color(0xFF78909C)
    }

    Card(
        modifier = modifier
            .height(80.dp)
            .clickable { onClick() },
        colors = CardDefaults.cardColors(
            containerColor = tintColor.copy(alpha = 0.08f)
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tintColor,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = imageType.label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

// MARK: - Follow-Up Suggestions

@Composable
fun FollowUpSuggestions(
    suggestions: List<String>,
    onSuggestionClick: (String) -> Unit
) {
    var visible by remember { mutableStateOf(false) }

    LaunchedEffect(suggestions) {
        visible = false
        delay(200)
        visible = true
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(animationSpec = tween(400)) + slideInVertically(
            initialOffsetY = { it / 4 },
            animationSpec = tween(400)
        )
    ) {
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(end = 8.dp)
        ) {
            items(suggestions) { suggestion ->
                SuggestionChip(
                    onClick = { onSuggestionClick(suggestion) },
                    label = {
                        Text(
                            suggestion,
                            style = MaterialTheme.typography.bodySmall,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    },
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)),
                    colors = SuggestionChipDefaults.suggestionChipColors(
                        containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.06f),
                        labelColor = MaterialTheme.colorScheme.primary
                    )
                )
            }
        }
    }
}

// MARK: - Intro View

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
                textAlign = TextAlign.Center,
                lineHeight = 24.sp
            )
        }

        Button(
            onClick = onAnalyzeClick,
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary
            ),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 12.dp)
        ) {
            Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Analyze Health")
        }
    }
}

// MARK: - Chat Bubble

@Composable
fun ChatBubble(
    message: ChatMessage,
    onCopy: () -> Unit = {},
    onBookmark: () -> Unit = {}
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
                .widthIn(max = 300.dp)
                .background(bgColor, shape)
                .padding(horizontal = 16.dp, vertical = 12.dp)
        ) {
            if (message.isLoading) {
                TypingIndicator()
            } else {
                MarkdownText(
                    text = message.content,
                    color = textColor
                )
            }
        }

        // Action buttons (copy / bookmark) for non-loading messages
        if (!message.isLoading && !isUser) {
            Row(
                modifier = Modifier.padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                IconButton(
                    onClick = onCopy,
                    modifier = Modifier.size(28.dp)
                ) {
                    Icon(
                        Icons.Default.ContentCopy,
                        contentDescription = "Copy",
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.outline
                    )
                }
                IconButton(
                    onClick = onBookmark,
                    modifier = Modifier.size(28.dp)
                ) {
                    Icon(
                        Icons.Default.BookmarkBorder,
                        contentDescription = "Bookmark",
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.outline
                    )
                }
            }
        }
    }
}

// MARK: - Enhanced Markdown Rendering

@Composable
fun MarkdownText(
    text: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    val lines = text.split("\n")
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        lines.forEach { line ->
            when {
                // Headings: ### heading
                line.trimStart().startsWith("###") -> {
                    Text(
                        text = parseInlineMarkdown(line.trimStart().removePrefix("###").trim()),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = color
                    )
                }
                line.trimStart().startsWith("##") -> {
                    Text(
                        text = parseInlineMarkdown(line.trimStart().removePrefix("##").trim()),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = color
                    )
                }
                line.trimStart().startsWith("#") -> {
                    Text(
                        text = parseInlineMarkdown(line.trimStart().removePrefix("#").trim()),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = color
                    )
                }
                // Numbered list: "1. item" or "2. item" etc.
                line.trimStart().matches(Regex("^\\d+\\.\\s+.*")) -> {
                    val content = line.trimStart().replaceFirst(Regex("^\\d+\\.\\s+"), "")
                    val number = line.trimStart().substringBefore(".")
                    Row(modifier = Modifier.padding(start = 4.dp)) {
                        Text(
                            text = "$number. ",
                            style = MaterialTheme.typography.bodyLarge,
                            color = color,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = parseInlineMarkdown(content),
                            style = MaterialTheme.typography.bodyLarge,
                            color = color
                        )
                    }
                }
                // Bulleted list: "- item" or "* item"
                line.trimStart().startsWith("- ") || line.trimStart().startsWith("* ") -> {
                    val content = line.trimStart().removePrefix("- ").removePrefix("* ")
                    Row(modifier = Modifier.padding(start = 4.dp)) {
                        Text(
                            text = "  \u2022  ",
                            style = MaterialTheme.typography.bodyLarge,
                            color = color
                        )
                        Text(
                            text = parseInlineMarkdown(content),
                            style = MaterialTheme.typography.bodyLarge,
                            color = color
                        )
                    }
                }
                // Empty line -> small spacer
                line.isBlank() -> {
                    Spacer(modifier = Modifier.height(4.dp))
                }
                // Normal text
                else -> {
                    Text(
                        text = parseInlineMarkdown(line),
                        style = MaterialTheme.typography.bodyLarge,
                        color = color
                    )
                }
            }
        }
    }
}

/**
 * Parses inline markdown: **bold**, *italic*, `code`
 */
fun parseInlineMarkdown(text: String): AnnotatedString {
    return buildAnnotatedString {
        var i = 0
        while (i < text.length) {
            when {
                // Bold: **text**
                i + 1 < text.length && text[i] == '*' && text[i + 1] == '*' -> {
                    val endIndex = text.indexOf("**", i + 2)
                    if (endIndex != -1) {
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                            append(text.substring(i + 2, endIndex))
                        }
                        i = endIndex + 2
                    } else {
                        append(text[i])
                        i++
                    }
                }
                // Italic: *text* (single asterisk, not followed by another)
                text[i] == '*' && (i + 1 >= text.length || text[i + 1] != '*') -> {
                    val endIndex = text.indexOf('*', i + 1)
                    if (endIndex != -1 && endIndex > i + 1) {
                        withStyle(SpanStyle(fontStyle = FontStyle.Italic)) {
                            append(text.substring(i + 1, endIndex))
                        }
                        i = endIndex + 1
                    } else {
                        append(text[i])
                        i++
                    }
                }
                // Inline code: `code`
                text[i] == '`' -> {
                    val endIndex = text.indexOf('`', i + 1)
                    if (endIndex != -1) {
                        withStyle(
                            SpanStyle(
                                fontFamily = FontFamily.Monospace,
                                background = Color(0x1A000000),
                                fontSize = 13.sp
                            )
                        ) {
                            append(" ${text.substring(i + 1, endIndex)} ")
                        }
                        i = endIndex + 1
                    } else {
                        append(text[i])
                        i++
                    }
                }
                else -> {
                    append(text[i])
                    i++
                }
            }
        }
    }
}

// Keep legacy parseMarkdown for backward compatibility if needed elsewhere
fun parseMarkdown(text: String): AnnotatedString {
    return parseInlineMarkdown(text)
}

@Composable
fun TypingIndicator() {
    val transition = rememberInfiniteTransition(label = "typingIndicator")
    val alpha by transition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(modifier = Modifier.size(8.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha), CircleShape))
        Box(modifier = Modifier.size(8.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha), CircleShape))
        Box(modifier = Modifier.size(8.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha), CircleShape))
    }
}

// MARK: - Chat Input Bar

@Composable
fun ChatInputBar(
    inputText: String,
    onTextChanged: (String) -> Unit,
    onSendClick: () -> Unit,
    onQuickActionClick: (QuickAction) -> Unit,
    onMicClick: () -> Unit,
    onImageClick: (() -> Unit)? = null,
    isRecording: Boolean,
    showSuggestions: Boolean,
    isLoading: Boolean,
    isImageAnalysisMode: Boolean = false
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
            // Image attach button in Image Analysis mode
            if (isImageAnalysisMode && onImageClick != null) {
                IconButton(
                    onClick = onImageClick,
                    modifier = Modifier
                        .background(
                            ImageAnalysisTeal.copy(alpha = 0.15f),
                            CircleShape
                        )
                        .size(40.dp)
                ) {
                    Icon(
                        Icons.Default.Image,
                        contentDescription = "Attach Image",
                        tint = ImageAnalysisTeal,
                        modifier = Modifier.size(20.dp)
                    )
                }
                Spacer(modifier = Modifier.width(4.dp))
            }

            TextField(
                value = inputText,
                onValueChange = onTextChanged,
                placeholder = {
                    Text(
                        if (isImageAnalysisMode) "Describe or ask about the image..." else "Ask Swastri...",
                        fontSize = 14.sp
                    )
                },
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
                Icon(
                    Icons.Default.ArrowUpward,
                    contentDescription = "Send",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
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

// MARK: - Analysis Result Overlay

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
