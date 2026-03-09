# AI Chat Screen Glassmorphic Visual Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite the visual layer of AIScreen.kt to use glassmorphism (glass() modifier, PremiumBackground, gradient accents) instead of flat Material colors, matching the app's premium design language.

**Architecture:** Single-file visual rewrite of `AIScreen.kt`. All composables are restructured visually but retain the same ViewModel integration, parameters, and behavioral logic. The `glass()` modifier from `HomeComponents.kt` and `PremiumBackground` from the same file provide the foundational visual primitives. No model or ViewModel changes needed.

**Tech Stack:** Jetpack Compose, Material3, Coil AsyncImage, existing glass()/PremiumBackground extensions

---

### Task 1: Redesign IntroView — Animated Avatar + Glass Quick Action Grid

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (lines 260-312, `IntroView` composable)

**Context:** The current `IntroView` is a plain Column with a static icon circle, text, and a single "Analyze Health" button. The redesign replaces this with an animated pulsing avatar and a 2x2 glass card grid using the existing `QuickAction.suggestions` list.

**Step 1: Replace IntroView with glassmorphic version**

Replace the `IntroView` composable (currently lines 260-312) with:

```kotlin
@Composable
fun IntroView(
    onQuickActionClick: (QuickAction) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(32.dp)
    ) {
        Spacer(modifier = Modifier.height(24.dp))

        // Animated AI Avatar with pulse
        val pulseTransition = rememberInfiniteTransition(label = "avatarPulse")
        val pulseScale by pulseTransition.animateFloat(
            initialValue = 1f,
            targetValue = 1.06f,
            animationSpec = infiniteRepeatable(
                animation = tween(3000, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "avatarScale"
        )
        val glowAlpha by pulseTransition.animateFloat(
            initialValue = 0.3f,
            targetValue = 0.6f,
            animationSpec = infiniteRepeatable(
                animation = tween(3000, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "glowAlpha"
        )

        Box(contentAlignment = Alignment.Center) {
            // Outer glow ring
            Box(
                modifier = Modifier
                    .size(120.dp)
                    .scale(pulseScale)
                    .background(
                        Brush.radialGradient(
                            colors = listOf(
                                PrimaryColor.copy(alpha = glowAlpha),
                                Color.Transparent
                            )
                        ),
                        CircleShape
                    )
            )
            // Avatar circle
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(PrimaryColor, PremiumColor.RoyalBlueEnd)
                        ),
                        CircleShape
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

        // 2x2 Glass Quick Action Grid with staggered entrance
        val suggestions = QuickAction.suggestions
        val gridIcons = listOf(
            Icons.Rounded.AutoAwesome,
            Icons.Default.Mic, // Sleep/moon stand-in
            Icons.Default.ArrowUpward, // Exercise stand-in
            Icons.Default.ContentCopy  // Nutrition stand-in
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            for (row in 0..1) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    for (col in 0..1) {
                        val index = row * 2 + col
                        if (index < suggestions.size) {
                            var visible by remember { mutableStateOf(false) }
                            LaunchedEffect(Unit) {
                                delay(index * 80L)
                                visible = true
                            }
                            AnimatedVisibility(
                                visible = visible,
                                enter = slideInVertically(
                                    initialOffsetY = { it / 3 },
                                    animationSpec = tween(400, easing = LinearOutSlowInEasing)
                                ) + fadeIn(animationSpec = tween(400)),
                                modifier = Modifier.weight(1f)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .glass(cornerRadius = 16.dp)
                                        .clickable { onQuickActionClick(suggestions[index]) }
                                        .padding(16.dp)
                                ) {
                                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Icon(
                                            gridIcons[index],
                                            contentDescription = null,
                                            tint = PrimaryColor,
                                            modifier = Modifier.size(20.dp)
                                        )
                                        Text(
                                            suggestions[index].title,
                                            style = MaterialTheme.typography.titleSmall,
                                            fontWeight = FontWeight.Medium,
                                            color = Color.White
                                        )
                                        Text(
                                            suggestions[index].description,
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
}
```

**Step 2: Update IntroView call site in AIScreen**

In `AIScreen` (around line 136), update the IntroView call to pass the new parameter:

```kotlin
// OLD:
IntroView(
    onAnalyzeClick = { viewModel.sendQuickAction(QuickAction.suggestions[0]) },
    modifier = Modifier.align(Alignment.Center)
)

// NEW:
IntroView(
    onQuickActionClick = { viewModel.sendQuickAction(it) },
    modifier = Modifier.align(Alignment.Center)
)
```

**Step 3: Add missing imports at top of file**

Add these imports if not already present:
```kotlin
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.style.TextOverflow
import com.swasthicare.mobile.ui.theme.PrimaryColor
import com.swasthicare.mobile.ui.theme.PremiumColor
```

**Step 4: Build and verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android): redesign AI intro view with animated avatar and glass quick action grid"
```

---

### Task 2: Redesign ChatBubble — Glass User Bubbles + Borderless AI Messages

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (lines 314-448, `ChatBubble` composable)

**Context:** The current `ChatBubble` uses flat `AppColors.primaryContainer`/`AppColors.surfaceVariant` backgrounds which look like skeleton placeholders on the dark PremiumBackground. User bubbles should use `glass()` with an indigo accent border. AI bubbles should be borderless — text floats directly on the gradient background. The typing indicator dots should use PrimaryColor. All behavioral logic (long-press menu, copy/share/bookmark, animations, AsyncImage) is preserved exactly.

**Step 1: Rewrite the ChatBubble composable**

Replace the entire `ChatBubble` composable (lines 314-448) with:

```kotlin
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatBubble(
    message: ChatMessage,
    onAnimationComplete: () -> Unit = {},
    onCopy: () -> Unit = {},
    onBookmark: () -> Unit = {}
) {
    val isUser = message.isUser
    val align = if (isUser) Alignment.End else Alignment.Start

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
        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = align) {
            if (isUser) {
                // --- USER BUBBLE: glass + indigo accent border ---
                Box(
                    modifier = Modifier
                        .widthIn(max = 300.dp)
                        .padding(start = 48.dp)
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

                    DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
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
            } else {
                // --- AI BUBBLE: borderless, text on gradient ---
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(end = 48.dp)
                        .combinedClickable(
                            onClick = {},
                            onLongClick = { if (!message.isLoading) showMenu = true }
                        )
                        .padding(horizontal = 4.dp, vertical = 4.dp)
                ) {
                    // "Swastri" label
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Icon(
                            Icons.Rounded.AutoAwesome,
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                            tint = PrimaryColor
                        )
                        Text(
                            "Swastri",
                            style = MaterialTheme.typography.labelSmall,
                            color = PrimaryColor
                        )
                    }

                    if (message.isLoading) {
                        // Glass pill for typing indicator
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

                    DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
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
```

**Step 2: Update TypingIndicator dot colors to PrimaryColor**

Replace the three dot lines in `TypingIndicator` (around line 596-599):

```kotlin
// OLD:
Box(modifier = Modifier.size(8.dp).background(AppColors.onSurfaceVariant.copy(alpha = a1), CircleShape))
Box(modifier = Modifier.size(8.dp).background(AppColors.onSurfaceVariant.copy(alpha = a2), CircleShape))
Box(modifier = Modifier.size(8.dp).background(AppColors.onSurfaceVariant.copy(alpha = a3), CircleShape))

// NEW:
Box(modifier = Modifier.size(8.dp).background(PrimaryColor.copy(alpha = a1), CircleShape))
Box(modifier = Modifier.size(8.dp).background(PrimaryColor.copy(alpha = a2), CircleShape))
Box(modifier = Modifier.size(8.dp).background(PrimaryColor.copy(alpha = a3), CircleShape))
```

**Step 3: Build and verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android): redesign chat bubbles with glass user bubbles and borderless AI messages"
```

---

### Task 3: Redesign ChatInputBar — Gradient Send Button + Glass Follow-Up Chips

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (lines 603-757, `ChatInputBar`, `QuickActionButton`, `FollowUpChips`)

**Context:** The input bar already uses `glass()` (good). The send button is a flat `AppColors.primary` circle. Replace with a gradient fill (indigo to violet). The mic button recording state should use a pulsing ring. The `FollowUpChips` should use `glass()` instead of `SuggestionChip`. Remove `QuickActionButton` since quick actions are now in the IntroView grid.

**Step 1: Rewrite ChatInputBar send button with gradient**

In `ChatInputBar`, replace the send button IconButton (around line 657-673) with:

```kotlin
// Gradient Send Button
val sendEnabled = inputText.isNotEmpty() && !isLoading
Box(
    modifier = Modifier
        .size(40.dp)
        .background(
            if (sendEnabled) Brush.linearGradient(
                colors = listOf(PrimaryColor, Color(0xFF7C3AED))
            ) else Brush.solidColor(Color.Gray.copy(alpha = 0.3f)),
            CircleShape
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
```

**Step 2: Add pulsing ring to mic button when recording**

Replace the mic button IconButton (around line 678-693) with:

```kotlin
// Mic Button with pulsing ring when recording
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
```

**Step 3: Rewrite FollowUpChips with glass pills**

Replace the `FollowUpChips` composable (around lines 725-757) with:

```kotlin
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
```

**Step 4: Remove QuickActionButton composable**

Delete the `QuickActionButton` composable (around lines 698-723) entirely. It is no longer used — quick actions are now in the IntroView grid.

**Step 5: Remove the LazyRow quick action suggestions from ChatInputBar**

In `ChatInputBar`, remove the `if (showSuggestions)` block that shows `QuickActionButton`s in a `LazyRow` (around lines 619-629). Also remove the `showSuggestions` parameter from the function signature and its call site in `AIScreen`.

In `AIScreen` (around line 218), remove the `showSuggestions` parameter:
```kotlin
// OLD:
showSuggestions = uiState.messages.isEmpty(),

// Remove this line entirely
```

Update `ChatInputBar` signature to remove `showSuggestions`:
```kotlin
// OLD:
fun ChatInputBar(
    inputText: String,
    onTextChanged: (String) -> Unit,
    onSendClick: () -> Unit,
    onQuickActionClick: (QuickAction) -> Unit,
    onMicClick: () -> Unit,
    isRecording: Boolean,
    showSuggestions: Boolean,
    isLoading: Boolean
)

// NEW:
fun ChatInputBar(
    inputText: String,
    onTextChanged: (String) -> Unit,
    onSendClick: () -> Unit,
    onMicClick: () -> Unit,
    isRecording: Boolean,
    isLoading: Boolean
)
```

Also remove `onQuickActionClick` from the call site in `AIScreen`:
```kotlin
// OLD:
onQuickActionClick = viewModel::sendQuickAction,

// Remove this line entirely
```

**Step 6: Update ChatInputBar placeholder text**

Change the placeholder from "Ask Swastri..." to "Ask anything...":
```kotlin
placeholder = { Text("Ask anything...", fontSize = 14.sp, color = Color.White.copy(alpha = 0.4f)) }
```

**Step 7: Build and verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 8: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android): redesign input bar with gradient send button, pulsing mic, glass follow-up chips"
```

---

### Task 4: Redesign HealthInsightCard + Scroll FAB + History Sheet

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (HealthInsightCard, scroll FAB area, ChatHistorySheet, ChatHistoryItem)

**Context:** HealthInsightCard needs a radial glow behind it. The scroll FAB should be a glass circle instead of Material FAB. The history sheet rows should use glass() and the selected row should have a PrimaryColor left border.

**Step 1: Add radial glow to HealthInsightCard**

Replace the `HealthInsightCard` composable (around lines 878-927) with:

```kotlin
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
```

**Step 2: Update MetricChip to use PrimaryColor for values**

Replace `MetricChip` (around lines 870-876):

```kotlin
@Composable
private fun MetricChip(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = PrimaryColor)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.5f))
    }
}
```

**Step 3: Replace scroll FAB with glass circle**

In `AIScreen`, replace the `SmallFloatingActionButton` block (around lines 186-201) with:

```kotlin
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
```

**Step 4: Redesign ChatHistoryItem with glass rows**

Replace the `ChatHistoryItem` composable (around lines 997-1046) with:

```kotlin
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
        // Indigo accent bar on left
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
```

**Step 5: Update ChatHistorySheet title and empty state colors**

In `ChatHistorySheet`, update title text color and empty state colors to work on dark backgrounds:

```kotlin
// Title
Text(
    text = "Chat History",
    style = MaterialTheme.typography.titleLarge,
    fontWeight = FontWeight.Bold,
    color = Color.White,
    modifier = Modifier.padding(bottom = 16.dp)
)

// Empty state icon tint
tint = Color.White.copy(alpha = 0.3f)

// Empty state text
color = Color.White.copy(alpha = 0.5f)
```

**Step 6: Add Canvas import**

Add to imports:
```kotlin
import androidx.compose.foundation.Canvas
```

**Step 7: Build and verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 8: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android): redesign health card with glow, glass scroll FAB, glass history rows"
```

---

### Task 5: Final Polish — Clean Up Unused Imports, Verify Full Screen Flow

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt`

**Context:** After the 4 structural tasks, the file needs import cleanup and a final consistency pass. Some imports from the old design (like `SuggestionChipDefaults`, specific `AppColors` usages for text colors) may be unused now. Also verify the Snackbar error toast and AnalysisResultOverlay still look right with the dark theme.

**Step 1: Remove unused imports**

Scan the import block and remove any that are no longer referenced. Likely candidates:
- `SuggestionChipDefaults` (if no longer used after FollowUpChips rewrite)
- Any `AppColors` references that were replaced with `Color.White` / `PrimaryColor`

**Step 2: Update AnalysisResultOverlay card colors for consistency**

In `AnalysisResultOverlay`, update the card backgrounds to use glass-compatible colors:
```kotlin
// Replace all CardDefaults.cardColors references:
// OLD: containerColor = AppColors.primaryContainer.copy(alpha = 0.3f)
// NEW: containerColor = PrimaryColor.copy(alpha = 0.1f)

// OLD: containerColor = AppColors.surfaceVariant.copy(alpha = 0.5f)
// NEW: containerColor = Color.White.copy(alpha = 0.05f)
```

**Step 3: Update Snackbar error toast for dark background**

The Snackbar is already using `AppColors.errorContainer` which should be fine, but verify it contrasts well.

**Step 4: Build and verify full flow**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "refactor(android): clean up AI screen imports and polish overlay colors for glassmorphic theme"
```
