package com.swastricare.health.ui.screens.ai

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import android.content.Intent
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.LocalTextStyle
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.rounded.AutoAwesome
import com.swastricare.health.data.repository.AIConversation
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import com.swastricare.health.R
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.models.ChatMessage
import com.swastricare.health.data.models.HealthMetrics
import com.swastricare.health.data.models.QuickAction
import com.swastricare.health.data.models.SnapFoodResult
import com.swastricare.health.domain.model.MealType
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.style.TextOverflow
import com.swastricare.health.ui.theme.PrimaryColor
import com.swastricare.health.ui.theme.PremiumColor
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import androidx.compose.foundation.Canvas
import androidx.compose.ui.focus.onFocusChanged
import android.app.Activity
import androidx.compose.ui.graphics.toArgb
import androidx.core.view.WindowCompat
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.swastricare.health.ui.components.TrackScreen

val Poppins = FontFamily(
    Font(R.font.poppins_light, FontWeight.Light),
    Font(R.font.poppins_regular, FontWeight.Normal),
    Font(R.font.poppins_medium, FontWeight.Medium),
    Font(R.font.poppins_semibold, FontWeight.SemiBold),
    Font(R.font.poppins_bold, FontWeight.Bold)
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIScreen(
    onFullScreenChange: (Boolean) -> Unit = {},
    viewModel: AIViewModel = hiltViewModel()
) {
    TrackScreen("AI")
    val uiState by viewModel.uiState.collectAsState()
    val isOnline by viewModel.networkMonitor.isConnected.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val hapticFeedback = LocalHapticFeedback.current
    val focusManager = LocalFocusManager.current

    // Consume any pending document context seeded by the Vault screen
    LaunchedEffect(Unit) {
        viewModel.loadPendingDocumentContext()
    }

    // Track whether chat input is focused
    var inputFocused by remember { mutableStateOf(false) }

    // Hide nav bar when input is focused or chat has messages
    val isExpanded = inputFocused || uiState.messages.isNotEmpty() || !uiState.showEmptyState

    // Notify parent to hide/show bottom nav
    LaunchedEffect(isExpanded) {
        onFullScreenChange(isExpanded)
    }

    // Permission launcher (microphone)
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            viewModel.toggleRecording()
        }
    }

    // Gallery picker
    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let { viewModel.onImagePicked(it.toString()) }
    }

    // Camera capture
    val context = LocalContext.current
    var cameraImageUri by remember { mutableStateOf<Uri?>(null) }
    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            cameraImageUri?.let { viewModel.onImagePicked(it.toString()) }
        }
    }

    // Permission launcher (camera)
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            cameraImageUri?.let { cameraLauncher.launch(it) }
        }
    }

    // Auto-scroll to bottom when new messages arrive or loading state changes
    val lastMessageContent = uiState.messages.lastOrNull()?.content
    val isLoading = uiState.isLoading
    LaunchedEffect(uiState.messages.size, lastMessageContent, isLoading) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    // Haptic feedback: light tap when sending, stronger tap when response arrives
    LaunchedEffect(isLoading) {
        if (isLoading) {
            hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        }
    }
    val lastMessage = uiState.messages.lastOrNull()
    LaunchedEffect(lastMessage?.id) {
        if (lastMessage != null && !lastMessage.isUser && !lastMessage.isLoading) {
            hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }

    val isDark = isSystemInDarkTheme()
    val view = LocalView.current
    DisposableEffect(isDark) {
        val activity = view.context as? Activity
        activity?.window?.let { window ->
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !isDark
        }
        onDispose {
            activity?.window?.let { window ->
                window.statusBarColor = android.graphics.Color.TRANSPARENT
                WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !isDark
            }
        }
    }
    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .imePadding()
        ) {
            // Header — uses the shared AppTopBar so the title style matches
            // every other screen in the app.
            com.swastricare.health.ui.components.AppTopBar(
                title = "Swastri AI",
                onBack = if (isExpanded) {
                    {
                        focusManager.clearFocus()
                        viewModel.clearChat()
                    }
                } else null,
                actions = {
                    IconButton(onClick = { viewModel.openHistorySheet() }) {
                        Icon(Icons.Default.History, contentDescription = "Chat History")
                    }
                    IconButton(onClick = {
                        focusManager.clearFocus()
                        viewModel.clearChat()
                    }) {
                        Icon(Icons.Default.Close, contentDescription = "Clear Chat")
                    }
                }
            )

            Box(modifier = Modifier.weight(1f)) {
                if (uiState.messages.isEmpty() && uiState.showEmptyState) {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Top
                    ) {
                        AIOrbVideo(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(260.dp)
                        )
                        IntroView(
                            userName = uiState.userName
                        )
                    }
                } else {
                    ChatMessageList(
                        messages = uiState.messages,
                        listState = listState,
                        analysisState = uiState.analysisState,
                        followUpSuggestions = uiState.followUpSuggestions,
                        onMarkMessageAnimated = { viewModel.markMessageAnimated(it) },
                        onMessageCopied = { viewModel.onMessageCopied() },
                        onMessageBookmarked = { viewModel.onMessageBookmarked() },
                        onFollowUpChipClick = { viewModel.sendFollowUp(it) },
                        onAddFoodToDiet = { viewModel.onAddToDietClicked(it) },
                        onScrollToBottomClick = {
                            scope.launch {
                                listState.animateScrollToItem(uiState.messages.size - 1)
                            }
                        },
                        onScrollToBottom = {
                            scope.launch {
                                if (uiState.messages.isNotEmpty()) {
                                    listState.animateScrollToItem(uiState.messages.size - 1)
                                }
                            }
                        }
                    )
                }
            }

            // Horizontally scrollable quick action chips above input
            if (uiState.messages.isEmpty() && uiState.showEmptyState) {
                QuickActionChips(
                    onQuickActionClick = { action ->
                        hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        viewModel.sendQuickAction(action)
                    }
                )
            }

            ChatInputBar(
                inputText = if (isOnline) uiState.inputText else "",
                onTextChanged = if (isOnline) viewModel::onInputTextChanged else { _ -> },
                onSendClick = {
                    if (isOnline) {
                        hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        focusManager.clearFocus()
                        viewModel.sendMessage()
                    }
                },
                onMicClick = {
                    hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                    if (uiState.isRecording) {
                         viewModel.toggleRecording()
                    } else {
                        permissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                    }
                },
                onCameraClick = {
                    try {
                        val file = java.io.File.createTempFile("photo_", ".jpg", context.cacheDir)
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        cameraImageUri = uri
                        val hasCameraPermission = androidx.core.content.ContextCompat.checkSelfPermission(
                            context, android.Manifest.permission.CAMERA
                        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (hasCameraPermission) {
                            cameraLauncher.launch(uri)
                        } else {
                            cameraPermissionLauncher.launch(android.Manifest.permission.CAMERA)
                        }
                    } catch (_: Exception) {
                        // ignore — file creation or FileProvider failure (e.g. no storage space)
                    }
                },
                onGalleryClick = {
                    galleryLauncher.launch("image/*")
                },
                isRecording = uiState.isRecording,
                isLoading = uiState.isLoading,
                onFocusChanged = { focused -> inputFocused = focused }
            )
        }

        // Analysis Overlay
        if (uiState.analysisState !is AnalysisState.Idle) {
            AnalysisResultOverlay(
                state = uiState.analysisState,
                onDismiss = { viewModel.dismissAnalysis() }
            )
        }

        // Image Type Selection Sheet
        if (uiState.showImageTypeSheet) {
            ImageTypeSheet(
                onTypeSelected = { viewModel.onImageTypeSelected(it) },
                onDismiss = { viewModel.dismissImageTypeSheet() }
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

        // Meal Type Selector Sheet
        if (uiState.showMealTypeSheet && uiState.pendingFoodResult != null) {
            MealTypeSelectorSheet(
                foodName = uiState.pendingFoodResult!!.name,
                onMealTypeSelected = { viewModel.logFoodToDiet(it) },
                onDismiss = { viewModel.dismissMealTypeSheet() }
            )
        }

        // Snackbar for diet logging success
        if (uiState.snackbarMessage != null) {
            LaunchedEffect(uiState.snackbarMessage) {
                delay(3000)
                viewModel.clearSnackbar()
            }
            Snackbar(
                modifier = Modifier
                    .padding(16.dp)
                    .align(Alignment.BottomCenter),
                containerColor = AppColors.primaryContainer,
                contentColor = AppColors.onBackground
            ) {
                Text(uiState.snackbarMessage!!)
            }
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

// ─────────────────────────────────────
// MARK: - ChatMessageList
// ─────────────────────────────────────

@Composable
private fun ChatMessageList(
    messages: List<ChatMessage>,
    listState: androidx.compose.foundation.lazy.LazyListState,
    analysisState: AnalysisState,
    followUpSuggestions: List<String>,
    onMarkMessageAnimated: (String) -> Unit,
    onMessageCopied: () -> Unit,
    onMessageBookmarked: () -> Unit,
    onFollowUpChipClick: (String) -> Unit,
    onAddFoodToDiet: ((SnapFoodResult) -> Unit)? = null,
    onScrollToBottomClick: () -> Unit,
    onScrollToBottom: () -> Unit = {}
) {
    // Scroll-to-bottom FAB visibility — must be computed before Box to avoid snapshot issues
    val showScrollFab by remember {
        derivedStateOf {
            listState.firstVisibleItemIndex < (messages.size - 2) &&
                messages.size > 2
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            itemsIndexed(messages, key = { _, msg -> msg.id }) { index, message ->
                ChatBubble(
                    message = message,
                    onAnimationComplete = { onMarkMessageAnimated(message.id) },
                    onCopy = onMessageCopied,
                    onBookmark = onMessageBookmarked,
                    onTextGrow = if (index == messages.size - 1) onScrollToBottom else null,
                    onAddFoodToDiet = onAddFoodToDiet
                )
                // Show health insight card below AI bubble if analysis is completed and response discusses health
                val hasHealthMetrics = remember(message.id, message.content) {
                    detectHealthMetrics(message.content).isNotEmpty()
                }
                val completedAnalysis = analysisState as? AnalysisState.Completed
                if (!message.isUser && !message.isLoading && hasHealthMetrics && completedAnalysis != null) {
                    HealthInsightCard(metrics = completedAnalysis.result.metrics)
                }
                // Show follow-up chips below the last AI message only
                val isLastMessage = index == messages.size - 1
                if (isLastMessage && !message.isUser && !message.isLoading) {
                    FollowUpChips(
                        suggestions = followUpSuggestions,
                        onChipClick = onFollowUpChipClick
                    )
                }
            }
        }

        // Scroll-to-bottom FAB
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
                    .clickable { onScrollToBottomClick() },
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

@Composable
fun IntroView(
    userName: String? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(28.dp)
    ) {
        // Welcome text
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = if (userName != null) "Hey $userName" else "Hey",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
            Text(
                text = "How can I help you today?",
                style = MaterialTheme.typography.bodyLarge,
                fontFamily = Poppins,
                color = AppColors.onBackground.copy(alpha = 0.6f)
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        // Medical disclaimer
        MedicalDisclaimerBanner()
    }
}

@Composable
private fun MedicalDisclaimerBanner(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .background(
                color = AppColors.surfaceVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = Icons.Outlined.Info,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = AppColors.onSurfaceVariant
        )
        Text(
            text = "For informational purposes only. Not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional.",
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant,
            lineHeight = 16.sp
        )
    }
}

@Composable
private fun QuickActionChips(
    onQuickActionClick: (QuickAction) -> Unit,
    modifier: Modifier = Modifier
) {
    val actions = QuickAction.suggestions
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = modifier.padding(bottom = 8.dp)
    ) {
        items(actions) { action ->
            Box(
                modifier = Modifier
                    .glass(cornerRadius = 20.dp)
                    .clickable { onQuickActionClick(action) }
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            ) {
                Text(
                    text = action.title,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Medium,
                    fontFamily = Poppins,
                    color = AppColors.onBackground,
                    maxLines = 1
                )
            }
        }
    }
}

@androidx.annotation.OptIn(UnstableApi::class)
@Composable
private fun AIOrbVideo(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val isDark = isSystemInDarkTheme()
    val videoAsset = if (isDark) "ai orb/ai orb 2.mp4" else "ai orb/Fluid White BG.mp4"
    var isFirstFrameRendered by remember { mutableStateOf(false) }
    val exoPlayer = remember(isDark) {
        isFirstFrameRendered = false
        ExoPlayer.Builder(context).build().apply {
            val uri = Uri.parse("file:///android_asset/$videoAsset")
            setMediaItem(MediaItem.fromUri(uri))
            repeatMode = Player.REPEAT_MODE_ALL
            playWhenReady = true
            volume = 0f
            prepare()
        }
    }
    DisposableEffect(isDark) {
        val listener = object : Player.Listener {
            override fun onRenderedFirstFrame() {
                isFirstFrameRendered = true
            }
        }
        exoPlayer.addListener(listener)
        onDispose {
            exoPlayer.removeListener(listener)
            exoPlayer.release()
        }
    }

    val alpha by animateFloatAsState(
        targetValue = if (isFirstFrameRendered) 1f else 0f,
        animationSpec = tween(durationMillis = 300),
        label = "orbVideoAlpha"
    )

    AndroidView(
        factory = { ctx ->
            PlayerView(ctx).apply {
                player = exoPlayer
                useController = false
                resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                setShutterBackgroundColor(android.graphics.Color.TRANSPARENT)
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
            }
        },
        modifier = modifier.graphicsLayer { this.alpha = alpha }
    )
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatBubble(
    message: ChatMessage,
    onAnimationComplete: () -> Unit = {},
    onCopy: () -> Unit = {},
    onBookmark: () -> Unit = {},
    onTextGrow: (() -> Unit)? = null,
    onAddFoodToDiet: ((SnapFoodResult) -> Unit)? = null
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
                            val hasTypeLabel = rawContent.startsWith("[Image: ") && rawContent.contains("]")
                            val typeLabel = if (hasTypeLabel) {
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
                            // If there is meaningful text alongside the image (i.e. not
                            // just the "[Image: X]" placeholder), render it below the
                            // image so the user always sees the question/context.
                            if (!hasTypeLabel && rawContent.isNotBlank()) {
                                Text(
                                    text = parseMarkdown(rawContent),
                                    color = AppColors.onBackground,
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontFamily = Poppins
                                )
                            }
                        }
                    } else {
                        Text(
                            text = parseMarkdown(message.content),
                            color = AppColors.onBackground,
                            style = MaterialTheme.typography.bodyLarge,
                            fontFamily = Poppins
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
                    Text("Swastri", style = MaterialTheme.typography.labelSmall, fontFamily = Poppins, color = PrimaryColor)
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
                    } else if (message.foodResult != null) {
                        // Food result — show only the card, skip raw text
                        FoodAnalysisCard(
                            foodResult = message.foodResult!!,
                            onAddToDiet = { onAddFoodToDiet?.invoke(message.foodResult!!) }
                        )
                    } else if (message.shouldAnimate) {
                        MarkdownContent(
                            content = message.content,
                            modifier = Modifier.fillMaxWidth()
                        )
                        LaunchedEffect(message.id) { onAnimationComplete() }
                    } else {
                        MarkdownContent(
                            content = message.content,
                            modifier = Modifier.fillMaxWidth()
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

                // Health metric badges extracted from AI response (skip for food analysis cards)
                if (!message.isLoading && message.content.isNotBlank() && message.foodResult == null) {
                    Spacer(modifier = Modifier.height(4.dp))
                    InlineHealthMetricsRow(
                        content = message.content,
                        modifier = Modifier.padding(start = 2.dp)
                    )
                }
            }
        }
    }
}

// MARK: - Smooth Line-by-Line Text Animation
@Composable
fun TypewriterText(
    fullText: String,
    color: Color,
    style: androidx.compose.ui.text.TextStyle,
    charDelayMillis: Long = 12L,
    onAnimationComplete: () -> Unit = {},
    onTextGrow: (() -> Unit)? = null
) {
    // Split into lines and reveal line by line with fade
    val lines = remember(fullText) { fullText.split("\n") }
    var visibleLineCount by remember(fullText) { mutableIntStateOf(0) }
    val totalLines = lines.size

    // Animate each line appearing
    LaunchedEffect(fullText) {
        visibleLineCount = 0
        for (i in 1..totalLines) {
            // Delay proportional to line length for natural pacing
            val lineLength = lines.getOrNull(i - 1)?.length ?: 0
            val lineDelay = when {
                lineLength == 0 -> 40L // empty line (paragraph break)
                lineLength < 20 -> 60L // short line (heading, bullet)
                lineLength < 60 -> 100L
                else -> 140L
            }
            delay(lineDelay)
            visibleLineCount = i
            onTextGrow?.invoke()
        }
        onAnimationComplete()
    }

    Column {
        lines.forEachIndexed { index, line ->
            if (index < visibleLineCount) {
                // Each line fades + slides in
                val lineAlpha = remember { Animatable(0f) }
                val lineOffset = remember { Animatable(8f) }
                LaunchedEffect(Unit) {
                    launch { lineAlpha.animateTo(1f, tween(200, easing = FastOutSlowInEasing)) }
                    launch { lineOffset.animateTo(0f, tween(200, easing = FastOutSlowInEasing)) }
                }

                Box(
                    modifier = Modifier
                        .graphicsLayer {
                            alpha = lineAlpha.value
                            translationY = lineOffset.value
                        }
                ) {
                    if (line.isBlank()) {
                        Spacer(modifier = Modifier.height(8.dp))
                    } else {
                        Text(
                            text = parseMarkdownLine(line),
                            color = color,
                            style = style,
                            fontFamily = Poppins
                        )
                    }
                }
            }
        }
    }
}

private fun parseMarkdownLine(rawLine: String): AnnotatedString {
    val builder = AnnotatedString.Builder()

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

    var cursor = 0
    for (match in INLINE_MARKDOWN_REGEX.findAll(line)) {
        if (match.range.first > cursor) builder.append(line.substring(cursor, match.range.first))
        val full = match.value
        when {
            full.startsWith("**") -> builder.withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(match.groupValues[1]) }
            full.startsWith("`") -> builder.withStyle(
                SpanStyle(
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    background = Color(0x22888888)
                )
            ) { append(match.groupValues[2]) }
            full.startsWith("*") -> builder.withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(match.groupValues[3]) }
            full.startsWith("_") -> builder.withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(match.groupValues[4]) }
        }
        cursor = match.range.last + 1
    }
    if (cursor < line.length) builder.append(line.substring(cursor))

    if (isH1 || isH2) builder.pop()

    return builder.toAnnotatedString()
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
    onCameraClick: () -> Unit = {},
    onGalleryClick: () -> Unit = {},
    isRecording: Boolean,
    isLoading: Boolean,
    onFocusChanged: (Boolean) -> Unit = {}
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

    // Animated neon border
    val neonTransition = rememberInfiniteTransition(label = "neon")
    val neonAngle by neonTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "neonAngle"
    )
    val neonColors = listOf(
        Color(0xFF1E3A5F),
        Color(0xFF1D4ED8),
        Color(0xFF2563EB),
        Color(0xFF1E3A5F)
    )
    val borderShape = RoundedCornerShape(28.dp)

    var showAttachMenu by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Text field with neon border
            Row(
                modifier = Modifier
                    .weight(1f)
                .drawBehind {
                    // if (!isLoading) return@drawBehind
                    val strokeWidth = 1.5.dp.toPx()
                    val radiusPx = 28.dp.toPx()

                    val outerPath = Path().apply {
                        addRoundRect(RoundRect(
                            rect = Rect(Offset.Zero, size),
                            cornerRadius = CornerRadius(radiusPx)
                        ))
                    }
                    val innerPath = Path().apply {
                        addRoundRect(RoundRect(
                            rect = Rect(
                                offset = Offset(strokeWidth, strokeWidth),
                                size = Size(size.width - strokeWidth * 2, size.height - strokeWidth * 2)
                            ),
                            cornerRadius = CornerRadius(radiusPx - strokeWidth)
                        ))
                    }

                    clipPath(outerPath) {
                        clipPath(innerPath, clipOp = ClipOp.Difference) {
                            rotate(neonAngle) {
                                drawCircle(
                                    brush = Brush.sweepGradient(neonColors),
                                    radius = maxOf(size.width, size.height),
                                    center = center
                                )
                            }
                        }
                    }
                }
                .glass(cornerRadius = 28.dp)
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Plus button (inside text field, left side)
            Box {
                IconButton(
                    onClick = { showAttachMenu = !showAttachMenu },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = "Attach",
                        tint = AppColors.onBackground.copy(alpha = 0.5f),
                        modifier = Modifier.size(20.dp)
                    )
                }
                DropdownMenu(
                    expanded = showAttachMenu,
                    onDismissRequest = { showAttachMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Take Photo") },
                        onClick = {
                            showAttachMenu = false
                            onCameraClick()
                        },
                        leadingIcon = {
                            Icon(Icons.Default.CameraAlt, contentDescription = null)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Choose from Gallery") },
                        onClick = {
                            showAttachMenu = false
                            onGalleryClick()
                        },
                        leadingIcon = {
                            Icon(Icons.Default.PhotoLibrary, contentDescription = null)
                        }
                    )
                }
            }
            BasicTextField(
                value = inputText,
                onValueChange = onTextChanged,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 12.dp)
                    .heightIn(min = 36.dp)
                    .onFocusChanged { onFocusChanged(it.isFocused) },
                maxLines = 4,
                textStyle = LocalTextStyle.current.copy(
                    fontSize = 14.sp,
                    fontFamily = Poppins,
                    color = AppColors.onBackground
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSendClick() }),
                cursorBrush = SolidColor(PrimaryColor),
                decorationBox = { innerTextField ->
                    Box(
                        modifier = Modifier.padding(vertical = 8.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        if (inputText.isEmpty()) {
                            Text(
                                "Ask anything...",
                                fontSize = 14.sp,
                                fontFamily = Poppins,
                                color = AppColors.onBackground.copy(alpha = 0.4f)
                            )
                        }
                        innerTextField()
                    }
                }
            )

            // Send or Mic button inside text field
            if (inputText.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .background(PrimaryColor, CircleShape)
                        .clip(CircleShape)
                        .clickable { onSendClick() },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.ArrowUpward,
                        contentDescription = "Send",
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                }
            } else {
                Box(contentAlignment = Alignment.Center) {
                    if (isRecording) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .scale(micRingScale)
                                .background(AppColors.error.copy(alpha = 0.2f), CircleShape)
                        )
                    }
                    IconButton(
                        onClick = onMicClick,
                        modifier = Modifier
                            .background(
                                if (isRecording) AppColors.error else Color.Transparent,
                                CircleShape
                            )
                            .size(32.dp)
                    ) {
                        Icon(
                            if (isRecording) Icons.Default.Stop else Icons.Default.Mic,
                            contentDescription = "Mic",
                            tint = if (isRecording) Color.White else AppColors.onBackground.copy(alpha = 0.5f),
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
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
private fun ImageTypeSheet(
    onTypeSelected: (ImageType) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                "What type of image is this?",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            // Food Photo — prominent green button
            Button(
                onClick = { onTypeSelected(ImageType.FoodPhoto) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF22C55E)
                )
            ) {
                Icon(
                    Icons.Default.Restaurant,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Food Photo", fontWeight = FontWeight.SemiBold)
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Divider with label
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                HorizontalDivider(modifier = Modifier.weight(1f))
                Text(
                    "Medical Image",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
                HorizontalDivider(modifier = Modifier.weight(1f))
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Medical image types (skip FoodPhoto since it's already shown above)
            ImageType.entries.filter { it != ImageType.FoodPhoto }.forEach { type ->
                OutlinedButton(
                    onClick = { onTypeSelected(type) },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(type.label)
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
        Text(label, style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
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
                color = AppColors.onBackground,
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
                                tint = AppColors.onBackground.copy(alpha = 0.3f),
                                modifier = Modifier.size(40.dp)
                            )
                            Text(
                                "No previous chats",
                                style = MaterialTheme.typography.bodyMedium,
                                color = AppColors.onSurfaceVariant
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
                color = AppColors.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (formattedDate.isNotEmpty()) {
                Text(
                    text = formattedDate,
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete",
                tint = AppColors.onBackground.copy(alpha = 0.4f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - FoodAnalysisCard
// ─────────────────────────────────────

@Composable
private fun FoodAnalysisCard(
    foodResult: SnapFoodResult,
    onAddToDiet: () -> Unit,
    modifier: Modifier = Modifier
) {
    val greenAccent = Color(0xFF22C55E)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.Default.Restaurant,
                contentDescription = null,
                tint = greenAccent,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = foodResult.name,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
        }

        // Calorie hero
        Text(
            text = "${foodResult.calories.toInt()} cal",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            fontFamily = Poppins,
            color = greenAccent
        )

        // Macro pills row
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            MacroPill("Protein", "${foodResult.proteinG.toInt()}g", Color(0xFF3B82F6))
            MacroPill("Carbs", "${foodResult.carbsG.toInt()}g", Color(0xFFF59E0B))
            MacroPill("Fat", "${foodResult.fatG.toInt()}g", Color(0xFFEF4444))
        }

        // Serving size
        Text(
            text = "Serving: ${foodResult.servingSize.toInt()} ${foodResult.servingUnit}",
            style = MaterialTheme.typography.bodySmall,
            fontFamily = Poppins,
            color = AppColors.onSurfaceVariant
        )

        // Add to Diet button
        Button(
            onClick = onAddToDiet,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = greenAccent),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(
                Icons.Default.Add,
                contentDescription = null,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                "Add to Diet",
                fontWeight = FontWeight.SemiBold,
                fontFamily = Poppins
            )
        }
    }
}

@Composable
private fun MacroPill(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .background(
                color = color.copy(alpha = 0.1f),
                shape = RoundedCornerShape(8.dp)
            )
            .padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontFamily = Poppins
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = color,
            fontFamily = Poppins
        )
    }
}

// ─────────────────────────────────────
// MARK: - MealTypeSelectorSheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MealTypeSelectorSheet(
    foodName: String,
    onMealTypeSelected: (MealType) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Add \"$foodName\" to...",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                fontFamily = Poppins,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            MealType.entries.forEach { mealType ->
                OutlinedButton(
                    onClick = { onMealTypeSelected(mealType) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Text(
                            text = mealType.displayName,
                            fontWeight = FontWeight.Medium,
                            fontFamily = Poppins
                        )
                        Text(
                            text = mealType.typicalTime,
                            style = MaterialTheme.typography.bodySmall,
                            color = AppColors.onSurfaceVariant,
                            fontFamily = Poppins
                        )
                    }
                }
            }
        }
    }
}
